package ReactionTurbineSystem {

    // ===== Value Types with Units =====
    
    value type Pressure {
        unit 'Pa';
    }
    
    value type Temperature {
        unit 'K';
    }
    
    value type Velocity {
        unit 'm/s';
    }
    
    value type MassFlowRate {
        unit 'kg/s';
    }
    
    value type AngularVelocity {
        unit 'rad/s';
    }
    
    value type Torque {
        unit 'N*m';
    }
    
    value type Power {
        unit 'W';
    }
    
    value type Efficiency {
        unit '1';
    }
    
    value type DegreeOfReaction {
        unit '1';
    }
    
    value type Voltage {
        unit 'V';
    }
    
    value type Current {
        unit 'A';
    }
    
    value type Frequency {
        unit 'Hz';
    }
    
    value type Dimensionless {
        unit '1';
    }
    
    // ===== Item Definitions =====
    
    item def WorkingFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute velocity : Velocity;
        attribute massFlowRate : MassFlowRate;
    }
    
    item def Steam :> WorkingFluid {
        attribute drynessFraction : Dimensionless = 1.0;
    }
    
    item def CombustionGas :> WorkingFluid {
        attribute specificHeatRatio : Dimensionless = 1.4;
    }
    
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
    }
    
    // ===== Port Definitions =====
    
    port def FluidInPort {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlowRate : MassFlowRate;
        out item fluid : WorkingFluid;
    }
    
    port def FluidOutPort {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlowRate : MassFlowRate;
        out item fluid : WorkingFluid;
    }
    
    port def MechanicalShaftPort {
        attribute angularVelocity : AngularVelocity;
        attribute torque : Torque;
        out attribute mechanicalPower : Power;
    }
    
    port def ElectricalOutputPort {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
        out item electricalPower : ElectricalPower;
    }
    
    port def ControlSignalPort {
        out attribute degreeOfReactionSetpoint : DegreeOfReaction;
        out attribute massFlowSetpoint : MassFlowRate;
        in attribute measuredEfficiency : Efficiency;
        in attribute measuredPower : Power;
        in attribute measuredAngularVelocity : AngularVelocity;
    }
    
    // ===== Requirements =====
    
    requirement def EnergyConservationRequirement {
        doc { The system shall conserve energy such that the electrical power output plus all losses shall equal the thermal and pressure energy input of the working fluid. }
        subject energyIn : Power;
        subject energyOut : Power;
        subject losses : Power;
        constraint { energyOut + losses == energyIn }
    }
    
    requirement def MinimumPowerOutputRequirement {
        doc { The system shall deliver a minimum electrical power output of 5 MW under nominal operating conditions. }
        subject electricalOutput : Power;
        constraint { electricalOutput >= 5000000 [W] }
    }
    
    requirement def EfficiencyThresholdRequirement {
        doc { The system controller shall maintain turbine efficiency above a target threshold of 0.85. If efficiency falls below this threshold, the controller shall adjust operating parameters to restore performance. }
        subject efficiency : Efficiency;
        attribute targetThreshold : Efficiency = 0.85;
        constraint { efficiency >= targetThreshold }
    }
    
    requirement def OptimalReactionRangeRequirement {
        doc { The degree of reaction shall be maintained within an optimal range of 0.4 to 0.6 to ensure balanced energy extraction between the stator and rotor. }
        subject degreeOfReaction : DegreeOfReaction;
        attribute minOptimal : DegreeOfReaction = 0.4;
        attribute maxOptimal : DegreeOfReaction = 0.6;
        constraint { degreeOfReaction >= minOptimal and degreeOfReaction <= maxOptimal }
    }
    
    requirement def PressureDropRequirement {
        doc { The rotor shall extract energy from a continued pressure drop across the rotor blades, consistent with the reaction turbine principle. }
        subject statorOutletPressure : Pressure;
        subject rotorOutletPressure : Pressure;
        constraint { rotorOutletPressure < statorOutletPressure }
    }
    
    // ===== Part Definitions =====
    
    part def Stator {
        doc { A set of fixed nozzles that accelerates the high-pressure working fluid, converting pressure energy into kinetic energy. }
        
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute inletTemperature : Temperature;
        attribute outletTemperature : Temperature;
        attribute outletVelocity : Velocity;
        attribute nozzleEfficiency : Efficiency = 0.95;
        attribute statorPressureDropFraction : Dimensionless;
        
        attribute statorEnergyExtraction : Power;
        
        action def accelerateFluid {
            in fluidInput : WorkingFluid;
            out fluidOutput : WorkingFluid;
            
            // Convert pressure to velocity through nozzle expansion
            first receiveFluid;
            then expandFluid;
            then dischargeFluid;
            
            action receiveFluid {
                in item receivedFluid : WorkingFluid;
            }
            
            action expandFluid {
                in item inputFluid : WorkingFluid;
                out item expandedFluid : WorkingFluid;
                // Pressure drops, velocity increases
            }
            
            action dischargeFluid {
                out item acceleratedFluid : WorkingFluid;
            }
        }
        
        satisfy EnergyConservationRequirement {
            subject energyIn = fluidIn.pressure * fluidIn.massFlowRate;
            subject energyOut = fluidOut.pressure * fluidOut.massFlowRate + (0.5 * fluidOut.massFlowRate * outletVelocity * outletVelocity);
            subject losses = (1.0 - nozzleEfficiency) * statorEnergyExtraction;
        }
    }
    
    part def Rotor {
        doc { A rotating component with blades that extracts energy from both the fluid velocity and a continued pressure drop. }
        
        port fluidIn : FluidOutPort;
        port fluidOut : FluidOutPort;
        port shaftOut : MechanicalShaftPort;
        
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute inletVelocity : Velocity;
        attribute outletVelocity : Velocity;
        attribute bladeTipSpeed : Velocity;
        attribute angularVelocity : AngularVelocity;
        attribute torque : Torque;
        attribute mechanicalPower : Power;
        attribute rotorEfficiency : Efficiency = 0.92;
        attribute rotorEnergyExtraction : Power;
        attribute degreeOfReaction : DegreeOfReaction;
        
        action def extractEnergy {
            in fluidInput : WorkingFluid;
            out fluidOutput : WorkingFluid;
            out mechanicalPowerOutput : Power;
            
            first receiveAcceleratedFluid;
            then deflectBlades;
            then extractPressureEnergy;
            then dischargeFluid;
            then transmitShaftPower;
            
            action receiveAcceleratedFluid {
                in item acceleratedFluid : WorkingFluid;
            }
            
            action deflectBlades {
                in item inputFluid : WorkingFluid;
                out item deflectedFluid : WorkingFluid;
                // Fluid imparts force on blades
            }
            
            action extractPressureEnergy {
                in item deflectedFluid : WorkingFluid;
                out item expandedFluid : WorkingFluid;
                // Continued pressure drop extracts additional energy
            }
            
            action dischargeFluid {
                out item exhaustFluid : WorkingFluid;
            }
            
            action transmitShaftPower {
                out power : Power;
            }
        }
        
        satisfy PressureDropRequirement {
            subject statorOutletPressure = inletPressure;
            subject rotorOutletPressure = outletPressure;
        }
        
        satisfy OptimalReactionRangeRequirement {
            subject degreeOfReaction = degreeOfReaction;
        }
    }
    
    part def Shaft {
        doc { Central rotating shaft that transmits mechanical power from the rotor to the generator. }
        
        port rotorEnd : MechanicalShaftPort;
        port generatorEnd : MechanicalShaftPort;
        
        attribute angularVelocity : AngularVelocity;
        attribute torque : Torque;
        attribute transmittedPower : Power;
        attribute torsionalStiffness : Real;
        attribute mechanicalLoss : Power;
    }
    
    part def Generator {
        doc { Converts rotational mechanical energy into electrical power. }
        
        port shaftIn : MechanicalShaftPort;
        port electricalOut : ElectricalOutputPort;
        
        attribute inputAngularVelocity : AngularVelocity;
        attribute inputTorque : Torque;
        attribute inputMechanicalPower : Power;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        attribute outputFrequency : Frequency;
        attribute outputPower : Power;
        attribute generatorEfficiency : Efficiency = 0.96;
        attribute poleCount : Integer = 2;
        
        action def generateElectricity {
            in mechanicalPowerInput : Power;
            in angularVelocityInput : AngularVelocity;
            out electricalPowerOutput : ElectricalPower;
            
            first receiveMechanicalPower;
            then convertToElectrical;
            then regulateOutput;
            then deliverPower;
            
            action receiveMechanicalPower {
                in power : Power;
            }
            
            action convertToElectrical {
                in power : Power;
                out electricalPower : ElectricalPower;
            }
            
            action regulateOutput {
                in electricalPower : ElectricalPower;
                out regulatedPower : ElectricalPower;
            }
            
            action deliverPower {
                out power : ElectricalPower;
            }
        }
        
        satisfy MinimumPowerOutputRequirement {
            subject electricalOutput = outputPower;
        }
    }
    
    part def TurbineController {
        doc { Actively manages the turbine process, monitors efficiency, and adjusts operating parameters to optimize the degree of reaction. }
        
        port controlInterface : ControlSignalPort;
        
        attribute targetEfficiency : Efficiency = 0.85;
        attribute targetDegreeOfReaction : DegreeOfReaction = 0.5;
        attribute measuredEfficiency : Efficiency;
        attribute measuredPower : Power;
        attribute measuredAngularVelocity : AngularVelocity;
        attribute adjustmentActive : Boolean = false;
        attribute minDegreeOfReaction : DegreeOfReaction = 0.4;
        attribute maxDegreeOfReaction : DegreeOfReaction = 0.6;
        attribute controlGain : Real = 0.1;
        
        state machine def ControllerStateMachine {
            
            state Initializing {
                entry { initializeController(); }
                do { performDiagnostics(); }
                exit { verifyReadiness(); }
            }
            
            state Monitoring {
                entry { beginMonitoring(); }
                do { continuouslyMonitorEfficiency(); }
                exit { logPerformance(); }
            }
            
            state Optimizing {
                entry { initiateOptimization(); }
                do { adjustDegreeOfReaction(); }
                exit { verifyRestoredEfficiency(); }
            }
            
            state FaultDetected {
                entry { raiseAlarm(); }
                do { executeSafeShutdown(); }
            }
            
            transition init_to_monitoring
                first Initializing
                then Monitoring
                when controllerReady;
            
            transition monitoring_to_optimizing
                first Monitoring
                then Optimizing
                when measuredEfficiency < targetEfficiency;
            
            transition optimizing_to_monitoring
                first Optimizing
                then Monitoring
                when measuredEfficiency >= targetEfficiency;
            
            transition any_to_fault
                source Monitoring
                then FaultDetected
                when measuredEfficiency < 0.5;
            
            transition fault_to_init
                first FaultDetected
                then Initializing
                when resetCommandReceived;
        }
        
        action def initializeController {
            // Initialize all controller parameters and sensors
        }
        
        action def performDiagnostics {
            // Run self-test on sensors and actuators
        }
        
        action def verifyReadiness {
            // Confirm system is ready for operation
        }
        
        action def beginMonitoring {
            // Start continuous monitoring loop
        }
        
        action def continuouslyMonitorEfficiency {
            // Read efficiency, power, and speed sensors
        }
        
        action def logPerformance {
            // Record performance metrics
        }
        
        action def initiateOptimization {
            // Begin optimization routine
        }
        
        action def adjustDegreeOfReaction {
            // Adjust stator nozzle positions or mass flow to optimize degree of reaction
            // Incrementally adjust toward target while staying within optimal range
        }
        
        action def verifyRestoredEfficiency {
            // Confirm efficiency is back above threshold
        }
        
        action def raiseAlarm {
            // Trigger alarm for low efficiency or fault
        }
        
        action def executeSafeShutdown {
            // Safely shut down the turbine
        }
        
        satisfy EfficiencyThresholdRequirement {
            subject efficiency = measuredEfficiency;
        }
        
        satisfy OptimalReactionRangeRequirement {
            subject degreeOfReaction = targetDegreeOfReaction;
        }
    }
    
    part def TurbineStage {
        doc { A single reaction turbine stage consisting of a matched stator and rotor pair. }
        
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port shaftOut : MechanicalShaftPort;
        
        part stator : Stator {
            attribute statorPressureDropFraction : Dimensionless = 0.5;
        }
        
        part rotor : Rotor {
            attribute degreeOfReaction : DegreeOfReaction = 0.5;
        }
        
        attribute stageEfficiency : Efficiency;
        attribute totalPressureDrop : Pressure;
        attribute stagePowerOutput : Power;
        attribute stageDegreeOfReaction : DegreeOfReaction;
        
        flow from stator.fluidOut to rotor.fluidIn of WorkingFluid;
        
        action def operateStage {
            in fluidInput : WorkingFluid;
            out fluidOutput : WorkingFluid;
            out mechanicalPower : Power;
            
            first statorAccelerate;
            then rotorExtract;
            
            action statorAccelerate : Stator::accelerateFluid {
                in fluidInput = fluidInput;
                out fluidOutput = statorOutletFluid;
            }
            
            action rotorExtract : Rotor::extractEnergy {
                in fluidInput = statorOutletFluid;
                out fluidOutput = fluidOutput;
                out mechanicalPowerOutput = mechanicalPower;
            }
        }
    }
    
    part def ReactionTurbinePowerSystem {
        doc { Complete reaction turbine power generation system integrating turbine stage, shaft, generator, and controller. }
        
        port fluidInlet : FluidInPort;
        port fluidOutlet : FluidOutPort;
        port electricalOutput : ElectricalOutputPort;
        
        part turbineStage : TurbineStage {
            attribute stageDegreeOfReaction : DegreeOfReaction = 0.5;
        }
        
        part shaft : Shaft {
            attribute mechanicalLoss : Power = 5000 [W];
        }
        
        part generator : Generator {
            attribute generatorEfficiency : Efficiency = 0.96;
        }
        
        part controller : TurbineController {
            attribute targetEfficiency : Efficiency = 0.85;
        }
        
        // Working fluid supply
        item workingFluid : Steam {
            attribute pressure = 8000000 [Pa];
            attribute temperature = 773 [K];
            attribute massFlowRate = 10 [kg/s];
        }
        
        // Electrical output
        item electricalOutput : ElectricalPower;
        
        // System-level attributes
        attribute systemEfficiency : Efficiency;
        attribute totalPowerOutput : Power;
        attribute systemDegreeOfReaction : DegreeOfReaction;
        attribute totalLosses : Power;
        
        // Connections
        flow from fluidInlet to turbineStage.fluidIn of WorkingFluid;
        flow from turbineStage.fluidOut to fluidOutlet of WorkingFluid;
        
        connection shaftConnection1 connect turbineStage.shaftOut to shaft.rotorEnd;
        connection shaftConnection2 connect shaft.generatorEnd to generator.shaftIn;
        
        connection electricalConnection connect generator.electricalOut to electricalOutput;
        
        connection controlToTurbine connect controller.controlInterface to turbineStage;
        connection controlToGenerator connect controller.controlInterface to generator;
        
        // System behavior
        state machine def SystemOperationStateMachine {
            
            state Standby {
                entry { initializeSystem(); }
            }
            
            state Starting {
                entry { openFluidValve(); }
                do { rampUpSpeed(); }
                exit { confirmStableOperation(); }
            }
            
            state NormalOperation {
                entry { engageController(); }
                do { sustainPowerGeneration(); }
            }
            
            state LoadAdjustment {
                entry { beginLoadAdjustment(); }
                do { modifyOperatingParameters(); }
                exit { confirmSteadyState(); }
            }
            
            state Shutdown {
                entry { closeFluidValve(); }
                do { coastDown(); }
            }
            
            transition standby_to_starting
                first Standby
                then Starting
                when startCommandReceived;
            
            transition starting_to_normal
                first Starting
                then NormalOperation
                when stableSpeedAchieved;
            
            transition normal_to_loadAdjustment
                first NormalOperation
                then LoadAdjustment
                when loadChangeDetected;
            
            transition loadAdjustment_to_normal
                first LoadAdjustment
                then NormalOperation
                when steadyStateConfirmed;
            
            transition normal_to_shutdown
                first NormalOperation
                then Shutdown
                when shutdownCommandReceived;
        }
        
        action def initializeSystem {
            // Initialize all subsystems and verify readiness
        }
        
        action def openFluidValve {
            // Open the working fluid inlet valve
        }
        
        action def rampUpSpeed {
            // Gradually increase rotor speed to operating level
        }
        
        action def confirmStableOperation {
            // Verify stable operation at target speed
        }
        
        action def engageController {
            // Activate the turbine controller
        }
        
        action def sustainPowerGeneration {
            // Maintain continuous power generation
        }
        
        action def beginLoadAdjustment {
            // Initiate load adjustment procedure
        }
        
        action def modifyOperatingParameters {
            // Adjust mass flow, degree of reaction, or other parameters
        }
        
        action def confirmSteadyState {
            // Confirm system has reached steady state
        }
        
        action def closeFluidValve {
            // Close the working fluid inlet valve
        }
        
        action def coastDown {
            // Allow rotor to coast to a stop
        }
        
        // System requirements satisfaction
        satisfy EnergyConservationRequirement {
            subject energyIn = fluidInlet.pressure * fluidInlet.massFlowRate;
            subject energyOut = totalPowerOutput;
            subject losses = totalLosses;
        }
        
        satisfy MinimumPowerOutputRequirement {
            subject electricalOutput = totalPowerOutput;
        }
        
        satisfy EfficiencyThresholdRequirement {
            subject efficiency = systemEfficiency;
        }
        
        satisfy OptimalReactionRangeRequirement {
            subject degreeOfReaction = systemDegreeOfReaction;
        }
    }
    
    // ===== Top-level package requirements =====
    
    requirement def ReactionTurbineSystemRequirement {
        doc { The reaction turbine power generation system shall efficiently convert the thermal and pressure energy of a working fluid into electrical power using a single turbine stage with a matched stator-rotor pair, an integrated controller, and a generator. }
        
        subject system : ReactionTurbinePowerSystem;
        
        constraint { system.systemEfficiency >= 0.85 }
        constraint { system.totalPowerOutput >= 5000000 [W] }
        constraint { system.systemDegreeOfReaction >= 0.4 and system.systemDegreeOfReaction <= 0.6 }
    }
    
    requirement def StatorAccelerationRequirement {
        doc { The stator shall accelerate the high-pressure working fluid through fixed nozzles, converting pressure energy into kinetic energy. }
        subject stator : Stator;
        constraint { stator.outletVelocity > 100 [m/s] }
        constraint { stator.outletPressure < stator.inletPressure }
    }
    
    requirement def RotorEnergyExtractionRequirement {
        doc { The rotor shall extract energy from both the fluid velocity and a continued pressure drop across the rotor blades, with the degree of reaction determining the energy split. }
        subject rotor : Rotor;
        constraint { rotor.outletPressure < rotor.inletPressure }
        constraint { rotor.degreeOfReaction >= 0.4 and rotor.degreeOfReaction <= 0.6 }
        constraint { rotor.mechanicalPower > 0 [W] }
    }
    
    requirement def ControllerOptimizationRequirement {
        doc { The controller shall continuously monitor turbine efficiency and adjust operating parameters to optimize the degree of reaction when efficiency falls below the target threshold. }
        subject controller : TurbineController;
        constraint { controller.targetEfficiency == 0.85 }
        constraint { controller.targetDegreeOfReaction >= 0.4 and controller.targetDegreeOfReaction <= 0.6 }
    }
    
    requirement def GeneratorConversionRequirement {
        doc { The generator shall convert rotational mechanical energy from the shaft into electrical power at a regulated voltage and frequency. }
        subject generator : Generator;
        constraint { generator.outputPower > 0 [W] }
        constraint { generator.outputFrequency == 50 [Hz] }
    }
    
}
