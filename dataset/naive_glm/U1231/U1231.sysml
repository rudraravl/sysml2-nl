package HolodeckSimulationSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def PowerLevel :> Real { unit "W" }
    value def Frequency :> Real { unit "Hz" }
    value def Resolution :> Real { unit "px" }
    value def FieldStrength :> Real { unit "N/m²" }
    value def Temperature :> Real { unit "°C" }
    value def MassFlowRate :> Real { unit "kg/s" }
    value def ProcessingLoad :> Real { unit "%" }
    value def Distance :> Real { unit "m" }
    value def Velocity :> Real { unit "m/s" }
    value def Pressure :> Real { unit "Pa" }
    value def HeartRate :> Real { unit "bpm" }
    value def Time :> Real { unit "s" }

    item def SimulationProgram {
        attribute programName : String;
        attribute environmentDescription : String;
        attribute maxParticipants : Integer;
        attribute physicsRuleset : String;
        attribute aiComplexity : Integer;
    }

    item def ParticipantData {
        attribute participantId : Integer;
        attribute position : Distance[3];
        attribute velocity : Velocity[3];
        attribute biometricHeartRate : HeartRate;
        attribute currentAction : String;
    }

    item def RenderCommand {
        attribute targetSubsystem : String;
        attribute commandType : String;
        attribute spatialCoordinates : Distance[3];
        attribute priority : Integer;
    }

    item def SensorReading {
        attribute sensorId : Integer;
        attribute timestamp : Time;
        attribute detectedEntities : ParticipantData[*];
        attribute environmentalPressure : Pressure;
        attribute environmentalTemperature : Temperature;
    }

    item def SafetyAlert {
        attribute alertType : String;
        attribute severity : Integer;
        attribute affectedSubsystem : String;
        attribute recommendedAction : String;
    }

    item def MatterPattern {
        attribute patternId : Integer;
        attribute patternName : String;
        attribute molecularComplexity : Integer;
        attribute requiredMass : MassValue;
    }

    value def MassValue :> Real { unit "kg" }

    item def ReplicatorCommand {
        attribute action : String; // "synthesize" or "recycle"
        attribute pattern : MatterPattern;
        attribute quantity : Integer;
    }

    // ===== Port Definitions =====
    port def CommandPort {
        out item commands : RenderCommand[*];
        in item acknowledgments : String[*];
    }

    port def SensorDataPort {
        out item readings : SensorReading[*];
    }

    port def ProcessorCommandPort {
        out item renderCommands : RenderCommand[*];
        out item replicatorCommands : ReplicatorCommand[*];
        in item sensorReadings : SensorReading[*];
        in item safetyAlerts : SafetyAlert[*];
    }

    port def SafetyMonitorPort {
        in item sensorReadings : SensorReading[*];
        in item processingLoad : ProcessingLoad;
        out item safetyAlerts : SafetyAlert[*];
        out item emergencyShutdown : Boolean;
    }

    port def InterlockControlPort {
        out item shutdownCommand : Boolean;
        out item limitEnforcement : Boolean;
        in item systemStatus : String;
    }

    // ===== Part Definitions =====

    part def HolographicProjector {
        attribute projectorId : Integer;
        attribute maxResolution : Resolution = 7680;
        attribute powerConsumption : PowerLevel = 150;
        port commandPort : CommandPort;

        attribute isActive : Boolean = false;
        attribute currentRenderLoad : ProcessingLoad = 0;

        action def RenderFrame {
            in command : RenderCommand;
            out status : String;
        }

        perform action renderLoop : RenderFrame {
            in command = commandPort.commands;
            out status = commandPort.acknowledgments;
        }
    }

    part def ForceFieldEmitter {
        attribute emitterId : Integer;
        attribute maxFieldStrength : FieldStrength = 50000;
        attribute responseTime : Time = 0.001;
        attribute isActive : Boolean = false;
        port commandPort : CommandPort;

        action def GenerateField {
            in command : RenderCommand;
            out status : String;
        }

        perform action fieldLoop : GenerateField {
            in command = commandPort.commands;
            out status = commandPort.acknowledgments;
        }
    }

    part def MatterReplicator {
        attribute replicatorId : Integer;
        attribute maxSynthesisRate : MassFlowRate = 0.5;
        attribute storedPatterns : MatterPattern[*];
        attribute isActive : Boolean = false;
        port commandPort : CommandPort;

        action def SynthesizeMatter {
            in command : ReplicatorCommand;
            out status : String;
        }

        action def RecycleMatter {
            in command : ReplicatorCommand;
            out status : String;
        }

        perform action replicatorLoop {
            in command : ReplicatorCommand = commandPort.commands;
            out status : String = commandPort.acknowledgments;

            if command.action == "synthesize" {
                perform SynthesizeMatter(in command = command, out status = status);
            } else if command.action == "recycle" {
                perform RecycleMatter(in command = command, out status = status);
            }
        }
    }

    part def SpatialSensor {
        attribute sensorId : Integer;
        attribute scanFrequency : Frequency = 1000;
        attribute range : Distance = 15.0;
        port sensorDataPort : SensorDataPort;

        action def ScanEnvironment {
            out reading : SensorReading;
        }

        perform action scanLoop : ScanEnvironment {
            out reading = sensorDataPort.readings;
        }
    }

    part def SimulationProcessor {
        attribute processorId : Integer = 1;
        attribute maxProcessingLoad : ProcessingLoad = 100;
        attribute currentLoad : ProcessingLoad = 0;
        attribute loadedProgram : SimulationProgram;

        port processorCommandPort : ProcessorCommandPort;
        port safetyMonitorOut : Port {
            out item processingLoad : ProcessingLoad;
        }

        state def ProcessorStateMachine {
            entry; then Idle;
            state Idle;
            state LoadingProgram;
            state InitializingEnvironment;
            state Running;
            state Paused;
            state EmergencyStopped;

            transition Idle_to_LoadingProgram
                first Idle
                then LoadingProgram
                when loadedProgram != null;

            transition Loading_to_Initializing
                first LoadingProgram
                then InitializingEnvironment
                accept ProgramLoaded;

            transition Initializing_to_Running
                first InitializingEnvironment
                then Running
                accept EnvironmentReady;

            transition Running_to_Paused
                first Running
                then Paused
                accept PauseCommand;

            transition Paused_to_Running
                first Paused
                then Running
                accept ResumeCommand;

            transition Running_to_EmergencyStopped
                first Running
                then EmergencyStopped
                accept EmergencyShutdown;

            transition Paused_to_EmergencyStopped
                first Paused
                then EmergencyStopped
                accept EmergencyShutdown;
        }

        exhibit state processorBehavior : ProcessorStateMachine;

        action def ProcessSensorData {
            in readings : SensorReading[*];
            out commands : RenderCommand[*];
            out replicatorCommands : ReplicatorCommand[*];
            out load : ProcessingLoad;
        }

        action def CalculatePhysics {
            in participantData : ParticipantData[*];
            out updatedCommands : RenderCommand[*];
        }

        action def UpdateAI {
            in participantData : ParticipantData[*];
            in program : SimulationProgram;
            out aiCommands : RenderCommand[*];
        }

        perform action processingLoop : ProcessSensorData {
            in readings = processorCommandPort.sensorReadings;
            out commands = processorCommandPort.renderCommands;
            out replicatorCommands = processorCommandPort.replicatorCommands;
            out load = safetyMonitorOut.processingLoad;
        }
    }

    part def SafetyInterlock {
        attribute interlockId : Integer = 1;
        attribute maxSafeLoad : ProcessingLoad = 95;
        attribute maxSafeTemperature : Temperature = 45.0;
        attribute maxSafeHeartRate : HeartRate = 200;
        attribute isArmed : Boolean = true;

        port safetyMonitorPort : SafetyMonitorPort;
        port interlockControlPort : InterlockControlPort;

        state def SafetyStateMachine {
            entry; then Monitoring;
            state Monitoring;
            state WarningEnforced;
            state EmergencyShutdownState;

            transition Monitoring_to_Warning
                first Monitoring
                then WarningEnforced
                when safetyMonitorPort.processingLoad > 90 || safetyMonitorPort.sensorReadings.environmentalTemperature > 40;

            transition Warning_to_Monitoring
                first WarningEnforced
                then Monitoring
                when safetyMonitorPort.processingLoad < 85 && safetyMonitorPort.sensorReadings.environmentalTemperature < 35;

            transition Monitoring_to_Emergency
                first Monitoring
                then EmergencyShutdownState
                when safetyMonitorPort.processingLoad > 95 || safetyMonitorPort.sensorReadings.environmentalTemperature > 45 || anyParticipantInDistress();

            transition Warning_to_Emergency
                first WarningEnforced
                then EmergencyShutdownState
                when safetyMonitorPort.processingLoad > 95 || safetyMonitorPort.sensorReadings.environmentalTemperature > 45;
        }

        exhibit state safetyBehavior : SafetyStateMachine;

        action def EvaluateSafety {
            in readings : SensorReading[*];
            in load : ProcessingLoad;
            out alert : SafetyAlert;
            out shutdown : Boolean;
        }

        action def EnforceLimits {
            out limitEnforced : Boolean;
        }

        perform action safetyLoop : EvaluateSafety {
            in readings = safetyMonitorPort.sensorReadings;
            in load = safetyMonitorPort.processingLoad;
            out alert = safetyMonitorPort.safetyAlerts;
            out shutdown = safetyMonitorPort.emergencyShutdown;
        }

        private def anyParticipantInDistress() : Boolean {
            return safetyMonitorPort.sensorReadings.detectedEntities.biometricHeartRate > maxSafeHeartRate;
        }
    }

    part def HolographicProjectorArray {
        attribute arrayId : Integer = 1;
        attribute projectorCount : Integer = 144;
        part projectors : HolographicProjector[144] {
            each projector.commandPort;
        }
        port aggregatedCommandPort : CommandPort;

        connection projectorsToAggregated : projectors.commandPort::commands > aggregatedCommandPort.commands;
    }

    part def ForceFieldEmitterGrid {
        attribute gridId : Integer = 1;
        attribute emitterCount : Integer = 96;
        part emitters : ForceFieldEmitter[96] {
            each emitter.commandPort;
        }
        port aggregatedCommandPort : CommandPort;

        connection emittersToAggregated : emitters.commandPort::commands > aggregatedCommandPort.commands;
    }

    part def MatterReplicatorArray {
        attribute arrayId : Integer = 1;
        attribute replicatorCount : Integer = 24;
        part replicators : MatterReplicator[24] {
            each replicator.commandPort;
        }
        port aggregatedCommandPort : CommandPort;

        connection replicatorsToAggregated : replicators.commandPort::commands > aggregatedCommandPort.commands;
    }

    part def SpatialSensorNetwork {
        attribute networkId : Integer = 1;
        attribute sensorCount : Integer = 48;
        part sensors : SpatialSensor[48] {
            each sensor.sensorDataPort;
        }
        port aggregatedSensorDataPort : SensorDataPort;

        connection sensorsToAggregated : sensors.sensorDataPort::readings > aggregatedSensorDataPort.readings;
    }

    // ===== Top-Level Holodeck System =====
    part def HolodeckSimulationSystem {
        attribute systemId : Integer = 1;
        attribute chamberDimensions : Distance[3] = [20.0, 20.0, 10.0];
        attribute isOperational : Boolean = false;

        part simulationProcessor : SimulationProcessor {
            attribute currentLoad : ProcessingLoad = 0;
        }

        part projectorArray : HolographicProjectorArray;
        part emitterGrid : ForceFieldEmitterGrid;
        part replicatorArray : MatterReplicatorArray;
        part sensorNetwork : SpatialSensorNetwork;
        part safetyInterlock : SafetyInterlock;

        // Connections
        connection processorToProjectors : simulationProcessor.processorCommandPort.renderCommands > projectorArray.aggregatedCommandPort.commands;
        connection processorToEmitters : simulationProcessor.processorCommandPort.renderCommands > emitterGrid.aggregatedCommandPort.commands;
        connection processorToReplicators : simulationProcessor.processorCommandPort.replicatorCommands > replicatorArray.aggregatedCommandPort.commands;

        connection sensorsToProcessor : sensorNetwork.aggregatedSensorDataPort.readings > simulationProcessor.processorCommandPort.sensorReadings;
        connection sensorsToSafety : sensorNetwork.aggregatedSensorDataPort.readings > safetyInterlock.safetyMonitorPort.sensorReadings;

        connection processorLoadToSafety : simulationProcessor.safetyMonitorOut.processingLoad > safetyInterlock.safetyMonitorPort.processingLoad;

        connection safetyToProcessor : safetyInterlock.safetyMonitorPort.safetyAlerts > simulationProcessor.processorCommandPort.safetyAlerts;
        connection safetyShutdownToProcessor : safetyInterlock.safetyMonitorPort.emergencyShutdown > simulationProcessor.processorCommandPort.safetyAlerts;

        connection safetyControlToProjectors : safetyInterlock.interlockControlPort.shutdownCommand > projectorArray.aggregatedCommandPort.acknowledgments;
        connection safetyControlToEmitters : safetyInterlock.interlockControlPort.shutdownCommand > emitterGrid.aggregatedCommandPort.acknowledgments;
        connection safetyControlToReplicators : safetyInterlock.interlockControlPort.shutdownCommand > replicatorArray.aggregatedCommandPort.acknowledgments;

        // System-level behavior
        state def HolodeckOperationalStates {
            entry; then PoweredOff;
            state PoweredOff;
            state Standby;
            state ProgramLoading;
            state SimulationActive;
            state SafetyShutdown;

            transition Off_to_Standby
                first PoweredOff
                then Standby
                accept PowerOn;

            transition Standby_to_Loading
                first Standby
                then ProgramLoading
                accept ProgramSelected;

            transition Loading_to_Active
                first ProgramLoading
                then SimulationActive
                accept ProgramLoaded;

            transition Active_to_Standby
                first SimulationActive
                then Standby
                accept ProgramEnded;

            transition Standby_to_Off
                first Standby
                then PoweredOff
                accept PowerOff;

            transition Active_to_SafetyShutdown
                first SimulationActive
                then SafetyShutdown
                accept EmergencyShutdown;

            transition SafetyShutdown_to_Standby
                first SafetyShutdown
                then Standby
                accept SafetyReset;
        }

        exhibit state systemBehavior : HolodeckOperationalStates;

        action def InitializeSimulation {
            in program : SimulationProgram;
            out environmentReady : Boolean;
        }

        action def RunSimulationLoop {
            in program : SimulationProgram;
            while systemBehavior.isActive(SimulationActive) {
                perform simulationProcessor.processingLoop;
                perform safetyInterlock.safetyLoop;
            }
        }

        perform action startupSequence : InitializeSimulation {
            in program = simulationProcessor.loadedProgram;
            out environmentReady = isOperational;
        }
    }

    // ===== Requirements =====
    requirement def HolodeckCoreRequirement {
        subject holodeck : HolodeckSimulationSystem;
        objective {
            The holodeck shall create fully immersive and physically interactive environments
            within a dedicated physical room by generating tangible objects, realistic visuals,
            and responsive physics.
        }
    }

    requirement def SimulationProcessorRequirement {
        subject processor : SimulationProcessor;
        objective {
            The processor shall load a simulation program defining the environment,
            number of participants, and world rules, and shall calculate consequences
            of participant actions in real-time.
        }
        attribute maxLatency : Time = 0.005;
    }

    requirement def HolographicProjectorArrayRequirement {
        subject projectorArray : HolographicProjectorArray;
        objective {
            The system shall include exactly 144 holographic projectors embedded in
            walls, ceiling, and floor, working together to paint the environment with
            light at a resolution indistinguishable from reality.
        }
        attribute requiredProjectorCount : Integer = 144;
        attribute minResolution : Resolution = 7680;
    }

    requirement def ForceFieldEmitterGridRequirement {
    subject emitterGrid : ForceFieldEmitterGrid;
        objective {
            The system shall include exactly 96 force field emitters interspersed with
            projectors, generating contained energy fields that feel solid to the touch,
            providing realistic tactile feedback and physical resistance.
        }
        attribute requiredEmitterCount : Integer = 96;
        attribute maxResponseTime : Time = 0.001;
    }

    requirement def MatterReplicatorRequirement {
        subject replicatorArray : MatterReplicatorArray;
        objective {
            The system shall include exactly 24 matter replicator units capable of
            synthesizing real physical matter from pre-programmed patterns and recycling
            that matter when no longer needed.
        }
        attribute requiredReplicatorCount : Integer = 24;
    }

    requirement def SpatialSensorNetworkRequirement {
        subject sensorNetwork : SpatialSensorNetwork;
        objective {
            The system shall include exactly 48 high-frequency spatial sensors that
            continuously scan the chamber, tracking precise position, velocity, and
            actions of every participant and simulated object in real-time.
        }
        attribute requiredSensorCount : Integer = 48;
        attribute minScanFrequency : Frequency = 1000;
    }

    requirement def SafetyInterlockRequirement {
        subject safetyInterlock : SafetyInterlock;
        objective {
            An independent safety system shall constantly monitor simulation parameters
            and participant well-being, enforcing safety limits or initiating emergency
            shutdown when processing load is too high, environmental hazards are detected,
            or participants show signs of distress.
        }
        attribute maxSafeProcessingLoad : ProcessingLoad = 95;
        attribute maxSafeTemperature : Temperature = 45.0;
        attribute maxSafeHeartRate : HeartRate = 200;
    }

    requirement def ContinuousOperationLoopRequirement {
        subject holodeck : HolodeckSimulationSystem;
        objective {
            The system shall maintain a continuous loop of sensing, processing, and
            rendering to create a seamless, dynamic, and fully interactive simulated world.
        }
    }

    // ===== Requirement Satisfaction =====
    satisfaction satisfy HolodeckCoreRequirement by holodeck.systemBehavior;
    satisfaction satisfy SimulationProcessorRequirement by simulationProcessor.processorBehavior;
    satisfaction satisfy HolographicProjectorArrayRequirement by projectorArray;
    satisfaction satisfy ForceFieldEmitterGridRequirement by emitterGrid;
    satisfaction satisfy MatterReplicatorRequirement by replicatorArray;
    satisfaction satisfy SpatialSensorNetworkRequirement by sensorNetwork;
    satisfaction satisfy SafetyInterlockRequirement by safetyInterlock.safetyBehavior;
    satisfaction satisfy ContinuousOperationLoopRequirement by holodeck.RunSimulationLoop;
}
