package HolodeckSimulationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def SimulationProgram {
        attribute environmentName : String;
        attribute maxParticipants : Natural;
        attribute physicsRules : String;
    }

    item def HolographicCommand {
        attribute sceneDescription : String;
        attribute intensity : Real;
        attribute refreshPeriod : TimeValue;
    }

    item def ForceFieldCommand {
        attribute fieldShape : String;
        attribute stiffness : Real;
        attribute refreshPeriod : TimeValue;
    }

    item def ReplicationCommand {
        attribute patternId : String;
        attribute quantity : Natural;
        attribute recycle : Boolean;
    }

    item def SensorData {
        attribute timestamp : TimeValue;
        attribute participantCount : Natural;
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute positionZ : LengthValue;
        attribute velocityX : SpeedValue;
        attribute velocityY : SpeedValue;
        attribute velocityZ : SpeedValue;
    }

    item def SafetyStatus {
        attribute processingLoad : Real;
        attribute environmentalHazard : Boolean;
        attribute participantDistress : Boolean;
        attribute shutdownRequired : Boolean;
    }

    item def EmergencyShutdownSignal {
        attribute reason : String;
        attribute timestamp : TimeValue;
    }

    port def ProgramPort {
        out program : SimulationProgram;
    }

    port def HolographicCommandPort {
        out command : HolographicCommand;
    }

    port def ForceFieldCommandPort {
        out command : ForceFieldCommand;
    }

    port def ReplicationCommandPort {
        out command : ReplicationCommand;
    }

    port def SensorDataPort {
        out data : SensorData;
    }

    port def SafetyStatusPort {
        out status : SafetyStatus;
    }

    port def EmergencyPort {
        out signal : EmergencyShutdownSignal;
    }

    part def SimulationProcessor {
        attribute processingLoad : Real;
        attribute currentProgram : SimulationProgram;

        port programIn : ~ProgramPort;
        port holographicOut : HolographicCommandPort;
        port forceFieldOut : ForceFieldCommandPort;
        port replicationOut : ReplicationCommandPort;
        port sensorDataIn : ~SensorDataPort;
        port safetyStatusIn : ~SafetyStatusPort;
        port emergencyIn : ~EmergencyPort;

        action def LoadProgram {
            in program : SimulationProgram;
        }

        action def ComputeCommands {
            in sensorInput : SensorData;
            in program : SimulationProgram;
            out holographicCmd : HolographicCommand;
            out forceFieldCmd : ForceFieldCommand;
            out replicationCmd : ReplicationCommand;
        }

        action def HaltAllSystems;

        state machine def ProcessorStateMachine {
            initial state Idle;
            state Loading {
                entry action loadProgram : LoadProgram;
            }
            state Running {
                do action computeCommands : ComputeCommands;
            }
            state EmergencyHalt {
                entry action haltAllSystems : HaltAllSystems;
            }
            transition loadTransition first Idle then Loading accept programIn.program;
            transition startTransition first Loading then Running;
            transition emergencyTransition first Running then EmergencyHalt accept emergencyIn.signal;
            transition resetTransition first EmergencyHalt then Idle;
        }
    }

    part def HolographicProjector {
        attribute index : Natural;
        port commandIn : ~HolographicCommandPort;
    }

    part def ForceFieldEmitter {
        attribute index : Natural;
        port commandIn : ~ForceFieldCommandPort;
    }

    part def MatterReplicator {
        attribute index : Natural;
        port commandIn : ~ReplicationCommandPort;
    }

    part def SpatialSensor {
        attribute index : Natural;
        port dataOut : SensorDataPort;
    }

    part def SafetyInterlock {
        attribute hazardDetected : Boolean = false;
        attribute distressDetected : Boolean = false;
        attribute loadExceeded : Boolean = false;

        port sensorDataIn : ~SensorDataPort;
        port statusOut : SafetyStatusPort;
        port emergencyOut : EmergencyPort;

        action def EvaluateSafety {
            in sensorInput : SensorData;
            in processorLoad : Real;
            out status : SafetyStatus;
            out emergency : EmergencyShutdownSignal;
        }

        action def TriggerEmergency;

        state machine def SafetyStateMachine {
            initial state Monitoring;
            state ShutdownTriggered {
                entry action triggerEmergency : TriggerEmergency;
            }
            transition triggerTransition first Monitoring then ShutdownTriggered;
            transition resetTransition first ShutdownTriggered then Monitoring;
        }
    }

    part def OperatorConsole {
        attribute availablePrograms : String[*];
        port programOut : ProgramPort;
    }

    part holodeckChamber {
        part operatorConsole : OperatorConsole;
        part processor : SimulationProcessor;
        part projectorArray : HolographicProjector[144];
        part emitterGrid : ForceFieldEmitter[96];
        part replicatorArray : MatterReplicator[24];
        part sensorNetwork : SpatialSensor[48];
        part safetySystem : SafetyInterlock;

        interface programInterface connect operatorConsole.programOut to processor.programIn {
            flow programFlow of SimulationProgram
                from operatorConsole.programOut.program to processor.programIn.program;
        }

        interface holographicInterface connect processor.holographicOut to projectorArray.commandIn {
            flow holographicFlow of HolographicCommand
                from processor.holographicOut.command to projectorArray.commandIn.command;
        }

        interface forceFieldInterface connect processor.forceFieldOut to emitterGrid.commandIn {
            flow forceFieldFlow of ForceFieldCommand
                from processor.forceFieldOut.command to emitterGrid.commandIn.command;
        }

        interface replicationInterface connect processor.replicationOut to replicatorArray.commandIn {
            flow replicationFlow of ReplicationCommand
                from processor.replicationOut.command to replicatorArray.commandIn.command;
        }

        interface sensorToProcessorInterface connect sensorNetwork.dataOut to processor.sensorDataIn {
            flow sensorDataFlow of SensorData
                from sensorNetwork.dataOut.data to processor.sensorDataIn.data;
        }

        interface sensorToSafetyInterface connect sensorNetwork.dataOut to safetySystem.sensorDataIn {
            flow safetySensorFlow of SensorData
                from sensorNetwork.dataOut.data to safetySystem.sensorDataIn.data;
        }

        interface safetyStatusInterface connect safetySystem.statusOut to processor.safetyStatusIn {
            flow safetyStatusFlow of SafetyStatus
                from safetySystem.statusOut.status to processor.safetyStatusIn.status;
        }

        interface emergencyInterface connect safetySystem.emergencyOut to processor.emergencyIn {
            flow emergencyFlow of EmergencyShutdownSignal
                from safetySystem.emergencyOut.signal to processor.emergencyIn.signal;
        }
    }

    requirement def ImmersionRequirement {
        doc
        /*
         * The holodeck shall provide a fully immersive and physically interactive environment
         * using at least 144 holographic projectors, 96 force field emitters, and 24 matter replicators.
         */
        attribute actualProjectorCount : Natural;
        attribute actualEmitterCount : Natural;
        attribute actualReplicatorCount : Natural;
        require constraint {
            actualProjectorCount >= 144 and
            actualEmitterCount >= 96 and
            actualReplicatorCount >= 24
        }
    }

    requirement def SensorCoverageRequirement {
        doc
        /*
         * The spatial sensor network shall comprise at least 48 high-frequency sensors
         * for real-time tracking of all participants and objects.
         */
        attribute actualSensorCount : Natural;
        require constraint { actualSensorCount >= 48 }
    }

    requirement def SafetyResponseRequirement {
        doc
        /*
         * The safety interlock shall detect hazards and initiate emergency shutdown
         * within the specified maximum response time.
         */
        attribute maxResponseTime : TimeValue;
        require constraint { maxResponseTime <= 100 [ms] }
    }

    requirement def RealTimeProcessingRequirement {
        doc
        /*
         * The simulation processor shall calculate physics, AI responses, and environmental
         * changes in real-time within the specified maximum latency.
         */
        attribute maxLatency : TimeValue;
        require constraint { maxLatency <= 20 [ms] }
    }

    requirement immersionReq : ImmersionRequirement {
        :>> actualProjectorCount = holodeckChamber.projectorArray->size();
        :>> actualEmitterCount = holodeckChamber.emitterGrid->size();
        :>> actualReplicatorCount = holodeckChamber.replicatorArray->size();
    }

    requirement sensorCoverageReq : SensorCoverageRequirement {
        :>> actualSensorCount = holodeckChamber.sensorNetwork->size();
    }

    requirement safetyResponseReq : SafetyResponseRequirement {
        :>> maxResponseTime = 100 [ms];
    }

    requirement realTimeProcessingReq : RealTimeProcessingRequirement {
        :>> maxLatency = 20 [ms];
    }

    satisfy immersionReq by holodeckChamber;
    satisfy sensorCoverageReq by holodeckChamber.sensorNetwork;
    satisfy safetyResponseReq by holodeckChamber.safetySystem;
    satisfy realTimeProcessingReq by holodeckChamber.processor;
}
